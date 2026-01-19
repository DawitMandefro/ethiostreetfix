import 'dart:convert';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/report_model.dart';
import 'cloudinary_service.dart';
import 'security_service.dart';

// SRS Section 3.2: Issue Reporting Service with secure data transmission
// SRS Section 6.1: Performance optimization and network resilience
class ReportService {
  // Lazy Firestore/auth access to avoid throwing when Firebase isn't configured
  CloudinaryService _cloudinaryService = CloudinaryService();
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  FirebaseFirestore? get _safeFirestore => _firestore ??= _tryGetFirestore();
  FirebaseAuth? get _safeAuth => _auth ??= _tryGetAuth();

  static FirebaseFirestore? _tryGetFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static FirebaseAuth? _tryGetAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  // In-memory fallback for offline/dev runs (won't persist across restarts)
  static final Map<String, Map<String, dynamic>> _localReports = {};

  // In-memory notifications for demo/offline mode. Persist to Firestore
  // or server-side notifications in production.
  static final List<Map<String, dynamic>> _localNotifications = [];

  // Use a single shared broadcast controller so multiple ReportService
  // instances (created across the app) see the same stream of events.
  static final StreamController<List<Map<String, dynamic>>>
  _notificationsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  Stream<List<Map<String, dynamic>>> notificationsForCurrentUser() {
    try {
      final auth = _safeAuth;

      // Always return a live broadcast stream (so future in-memory emits are
      // observed). For local/demo mode seed the controller with the current
      // snapshot of notifications.
      if (_safeFirestore == null || auth?.currentUser == null) {
        final list = _localNotifications
            .where(
              (n) => n['user'] == (auth?.currentUser?.email ?? 'demo@local'),
            )
            .toList()
            .reversed
            .toList();
        // schedule a microtask to push initial value to the controller so
        // listeners that subscribe synchronously receive the seed event.
        scheduleMicrotask(() {
          if (!_notificationsController.isClosed) {
            _notificationsController.add(list);
          }
        });
        return _notificationsController.stream;
      }

      // TODO: implement Firestore-backed notifications collection
      return _notificationsController.stream;
    } catch (_) {
      return Stream.value([]);
    }
  }

  // SRS Section 3.3: Mark a notification as read in both Firestore and local/demo mode
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final firestore = _safeFirestore;
      final auth = _safeAuth;

      if (firestore == null) {
        // Local/demo fallback: update in-memory list and emit updated snapshot
        for (var n in _localNotifications) {
          if (n['id'] == notificationId) {
            n['read'] = true;
            break;
          }
        }
        scheduleMicrotask(() {
          if (!_notificationsController.isClosed) {
            final list = _localNotifications
                .where(
                  (n) =>
                      n['user'] == (auth?.currentUser?.email ?? 'demo@local'),
                )
                .toList()
                .reversed
                .toList();
            _notificationsController.add(list);
          }
        });
        return;
      }

      await firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      print('Error marking notification as read (report service): $e');
    }
  }

  // SRS Section 3.3: Mark all notifications as read (local/demo or Firestore)
  Future<void> markAllNotificationsAsRead(String userEmail) async {
    try {
      final firestore = _safeFirestore;

      if (firestore == null) {
        for (var n in _localNotifications) {
          if (n['user'] == userEmail) n['read'] = true;
        }
        scheduleMicrotask(() {
          if (!_notificationsController.isClosed) {
            final list = _localNotifications
                .where((n) => n['user'] == userEmail)
                .toList()
                .reversed
                .toList();
            _notificationsController.add(list);
          }
        });
        return;
      }

      final batch = firestore.batch();
      final snapshot = await firestore
          .collection('notifications')
          .where('userEmail', isEqualTo: userEmail)
          .where('read', isEqualTo: false)
          .get();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read (report service): $e');
    }
  }

  Future<String?> submitReport({
    required String title,
    required String description,
    required String location,
    required double latitude,
    required double longitude,
    Uint8List? imageBytes,
    XFile? xFile,
    String? imageUrl,
  }) async {
    try {
      final auth = _safeAuth;
      final firestore = _safeFirestore;

      // If auth backend isn't available, use a demo user for local mode
      final userEmail = auth?.currentUser?.email ?? 'demo@local';
      final userId = auth?.currentUser?.uid ?? 'demo-user';

      String? finalImageUrl = imageUrl;

      // Attempt image upload but don't fail the entire report if it fails
      if ((imageBytes != null) || (xFile != null)) {
        try {
          if (xFile != null) {
            final bytes = await xFile.readAsBytes();
            finalImageUrl = await _cloudinaryService.uploadImageBytes(
              bytes,
              userId,
              xFile.name,
            );
          } else if (imageBytes != null) {
            finalImageUrl = await _cloudinaryService.uploadImageBytes(
              imageBytes,
              userId,
              'image.jpg',
            );
          }
        } catch (e, st) {
          // Non-fatal: continue without image but log the issue
          print('Image upload failed (continuing without image): $e\n$st');
          finalImageUrl = null;
        }
      }

      // Build report payload and allow SecurityService to encrypt/sanitize it
      final reportData = {
        'title': title,
        'description': description,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrl': finalImageUrl,
        'reportedBy': userEmail,
        'status': ReportStatus.pending.name,
        'createdAt': firestore != null
            ? FieldValue.serverTimestamp()
            : DateTime.now(),
        'updatedAt': firestore != null
            ? FieldValue.serverTimestamp()
            : DateTime.now(),
      };

      final encrypted = SecurityService.encryptPayload(reportData);

      if (firestore == null) {
        // Local fallback: store in-memory and return synthetic id
        final id = 'local-${DateTime.now().millisecondsSinceEpoch}';
        final map = Map<String, dynamic>.from(encrypted as Map);
        // ensure id is present so round-trips (export, status history) keep id
        map['id'] = id;
        _localReports[id] = map;
        return id;
      }

      final docRef = await firestore
          .collection('reports')
          .add(encrypted as Map<String, dynamic>);

      await _createStatusHistory(
        docRef.id,
        ReportStatus.pending,
        'Report submitted',
      );

      return docRef.id;
    } catch (e, st) {
      print('Error submitting report: $e\n$st');
      rethrow;
    }
  }

  // SRS Section 3.3: Get reports for current user (issue tracking)
  Stream<List<StreetReport>> getUserReports() {
    final auth = _safeAuth;
    final firestore = _safeFirestore;

    if (firestore == null || auth?.currentUser == null) {
      // Local/dev fallback
      final local = _localReports.values
          .where(
            (r) =>
                r['reportedBy'] == (auth?.currentUser?.email ?? 'demo@local'),
          )
          .map((m) => StreetReport.fromMap(m))
          .toList();
      local.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(local);
    }

    return firestore
        .collection('reports')
        .where('reportedBy', isEqualTo: auth!.currentUser!.email)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => StreetReport.fromFirestore(doc))
              .toList();
          // Sort locally by createdAt descending to avoid requiring a composite index
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Export the current user's reports as a JSON string. Includes a small
  /// metadata block (exportedAt, theme, analyticsOptIn) to make the output
  /// useful for audits and support. This method is safe in offline/demo
  /// mode (returns local fallback reports).
  Future<String> exportUserReportsJson() async {
    try {
      final reports = <StreetReport>[];
      final firestore = _safeFirestore;
      final auth = _safeAuth;

      if (firestore == null || auth?.currentUser == null) {
        reports.addAll(
          _localReports.values
              .where(
                (r) =>
                    r['reportedBy'] ==
                    (auth?.currentUser?.email ?? 'demo@local'),
              )
              .map((m) => StreetReport.fromMap(m)),
        );
      } else {
        final snapshot = await firestore
            .collection('reports')
            .where('reportedBy', isEqualTo: auth!.currentUser!.email)
            .get();
        reports.addAll(snapshot.docs.map((d) => StreetReport.fromFirestore(d)));
      }

      // Convert to serializable maps and normalise timestamps
      final list = reports.map((r) {
        final map = r.toFirestore();
        // replace Timestamp objects with ISO strings
        if (map['createdAt'] is Timestamp) {
          map['createdAt'] = (map['createdAt'] as Timestamp)
              .toDate()
              .toIso8601String();
        }
        if (map['updatedAt'] is Timestamp) {
          map['updatedAt'] = (map['updatedAt'] as Timestamp)
              .toDate()
              .toIso8601String();
        }
        return {...map, 'id': r.id};
      }).toList();

      // include small metadata to improve usefulness for support
      final meta = {
        'exportedAt': DateTime.now().toIso8601String(),
        'app': 'EthioStreetFix',
        'version': '1.0.0',
      };

      final payload = {'meta': meta, 'reports': list};
      return const JsonEncoder.withIndent('  ').convert(payload);
    } catch (e, st) {
      print('exportUserReportsJson error: $e\n$st');
      rethrow;
    }
  }

  /// Export all reports in the system as JSON (admins only). Safe in
  /// offline/demo mode.
  Future<String> exportAllReportsJson() async {
    try {
      final reports = <StreetReport>[];
      final firestore = _safeFirestore;

      if (firestore == null) {
        reports.addAll(
          _localReports.values.map((m) => StreetReport.fromMap(m)),
        );
      } else {
        final snapshot = await firestore.collection('reports').get();
        reports.addAll(snapshot.docs.map((d) => StreetReport.fromFirestore(d)));
      }

      final list = reports.map((r) {
        final map = r.toFirestore();
        if (map['createdAt'] is Timestamp) {
          map['createdAt'] = (map['createdAt'] as Timestamp)
              .toDate()
              .toIso8601String();
        }
        if (map['updatedAt'] is Timestamp) {
          map['updatedAt'] = (map['updatedAt'] as Timestamp)
              .toDate()
              .toIso8601String();
        }
        return {...map, 'id': r.id};
      }).toList();

      final meta = {
        'exportedAt': DateTime.now().toIso8601String(),
        'app': 'EthioStreetFix',
        'version': '1.0.0',
      };
      final payload = {'meta': meta, 'reports': list};
      return const JsonEncoder.withIndent('  ').convert(payload);
    } catch (e, st) {
      print('exportAllReportsJson error: $e\n$st');
      rethrow;
    }
  }

  // SRS Section 3.3: Get all reports (for authorities)
  Stream<List<StreetReport>> getAllReports({ReportStatus? statusFilter}) {
    final firestore = _safeFirestore;
    if (firestore == null) {
      final list = _localReports.values
          .map((m) => StreetReport.fromMap(m))
          .where((r) => statusFilter == null || r.status == statusFilter)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(list);
    }

    Query query = firestore.collection('reports');

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => StreetReport.fromFirestore(doc))
          .toList();
      // If createdAt exists, sort descending locally
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // SRS Section 3.4: Authority issue management
  Future<void> updateReportStatus({
    required String reportId,
    required ReportStatus newStatus,
    String? resolvedBy,
    String? rejectionReason,
  }) async {
    try {
      final auth = _safeAuth;
      final firestore = _safeFirestore;

      final userEmail = auth?.currentUser?.email ?? 'demo@local';

      if (firestore == null) {
        // Local fallback: update in-memory report
        final existing = _localReports[reportId];
        if (existing == null) throw Exception('Report not found');
        existing['status'] = newStatus.name;
        existing['updatedAt'] = DateTime.now();
        if (resolvedBy != null) existing['resolvedBy'] = resolvedBy;
        if (rejectionReason != null)
          existing['rejectionReason'] = rejectionReason;

        // Create audit/log entries locally
        await _createAuditLog(
          reportId: reportId,
          action: 'STATUS_UPDATE',
          performedBy: userEmail,
          previousStatus: existing['status'] ?? 'unknown',
          newStatus: newStatus.name,
        );

        await _createStatusHistory(
          reportId,
          newStatus,
          _getStatusNote(newStatus, rejectionReason),
        );

        // Emit a demo notification for local/offline mode so the UI can
        // observe status changes without Firestore/FCM configured.
        try {
          final notification = {
            'id': 'n-${DateTime.now().millisecondsSinceEpoch}',
            'user': userEmail,
            'reportId': reportId,
            'message': 'Your report has been updated to ${newStatus.name}',
            'status': newStatus.name,
            'createdAt': DateTime.now().toIso8601String(),
          };
          _localNotifications.add(notification);
          if (!_notificationsController.isClosed) {
            _notificationsController.add(
              _localNotifications
                  .where((n) => n['user'] == userEmail)
                  .toList()
                  .reversed
                  .toList(),
            );
          }
        } catch (_) {}

        return;
      }

      final reportRef = firestore.collection('reports').doc(reportId);
      final reportDoc = await reportRef.get();

      if (!reportDoc.exists) {
        throw Exception('Report not found');
      }

      final currentStatus = StreetReport.fromFirestore(reportDoc).status;

      // SRS Section 3.4: Update report status
      await reportRef.update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
        if (resolvedBy != null) 'resolvedBy': resolvedBy,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      });

      // SRS Section 3.4: Create audit log entry
      await _createAuditLog(
        reportId: reportId,
        action: 'STATUS_UPDATE',
        performedBy: userEmail,
        previousStatus: currentStatus.name,
        newStatus: newStatus.name,
      );

      // SRS Section 3.3: Create status history entry
      String statusNote = _getStatusNote(newStatus, rejectionReason);
      await _createStatusHistory(reportId, newStatus, statusNote);
      // SRS Section 3.3: Trigger notification (in-memory demo + stream)
      try {
        final userEmail = auth?.currentUser?.email ?? 'demo@local';
        final notification = {
          'id': 'n-${DateTime.now().millisecondsSinceEpoch}',
          'user': userEmail,
          'reportId': reportId,
          'message': 'Your report has been updated to ${newStatus.name}',
          'status': newStatus.name,
          'createdAt': DateTime.now().toIso8601String(),
        };
        _localNotifications.add(notification);
        if (!_notificationsController.isClosed) {
          _notificationsController.add(
            _localNotifications
                .where((n) => n['user'] == userEmail)
                .toList()
                .reversed
                .toList(),
          );
        }
      } catch (_) {}
      // SRS Section 3.3: Trigger notification (if implemented)
      // await _notifyUserOfStatusChange(reportId, newStatus);
    } catch (e) {
      print('Error updating report status: $e');
      rethrow;
    }
  }

  String _getStatusNote(ReportStatus status, String? rejectionReason) {
    switch (status) {
      case ReportStatus.inProgress:
        return 'Issue is being addressed';
      case ReportStatus.fixed:
        return 'Issue has been resolved';
      case ReportStatus.rejected:
        return rejectionReason ?? 'Report was rejected';
      case ReportStatus.pending:
        return 'Report is pending review';
    }
  }

  // SRS Section 3.4: Audit logging for authority actions
  Future<void> _createAuditLog({
    required String reportId,
    required String action,
    required String performedBy,
    required String previousStatus,
    required String newStatus,
  }) async {
    try {
      final firestore = _safeFirestore;
      if (firestore == null) {
        // local fallback: append to local report's audit log list
        final r = _localReports[reportId];
        if (r != null) {
          final logs =
              (r['auditLogs'] as List<dynamic>?) ?? <Map<String, dynamic>>[];
          logs.insert(0, {
            'reportId': reportId,
            'action': action,
            'performedBy': performedBy,
            'previousStatus': previousStatus,
            'newStatus': newStatus,
            'timestamp': DateTime.now(),
          });
          r['auditLogs'] = logs;
        }
        return;
      }

      await firestore.collection('audit_logs').add({
        'reportId': reportId,
        'action': action,
        'performedBy': performedBy,
        'previousStatus': previousStatus,
        'newStatus': newStatus,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating audit log: $e');
      // Don't rethrow - audit logging failure shouldn't block the main operation
    }
  }

  // SRS Section 3.4: Query audit logs (by user/reportId/date-range) with local fallback
  Stream<List<Map<String, dynamic>>> getAuditLogs({
    String? performedBy,
    String? reportId,
    DateTime? start,
    DateTime? end,
  }) {
    final firestore = _safeFirestore;

    if (firestore == null) {
      // Collect from local in-memory reports and flatten
      final logs = <Map<String, dynamic>>[];
      for (var r in _localReports.values) {
        final entries = (r['auditLogs'] as List<dynamic>?) ?? [];
        for (var e in entries) {
          final item = Map<String, dynamic>.from(e as Map);
          if (performedBy != null && item['performedBy'] != performedBy)
            continue;
          if (reportId != null && item['reportId'] != reportId) continue;
          final ts = item['timestamp'] as DateTime?;
          if (start != null && (ts == null || ts.isBefore(start))) continue;
          if (end != null && (ts == null || ts.isAfter(end))) continue;
          logs.add(item);
        }
      }
      // sort
      logs.sort((a, b) {
        final aTs = a['timestamp'] as DateTime?;
        final bTs = b['timestamp'] as DateTime?;
        if (aTs == null && bTs == null) return 0;
        if (aTs == null) return 1;
        if (bTs == null) return -1;
        return bTs.compareTo(aTs);
      });
      return Stream.value(logs);
    }

    try {
      var query = firestore
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(500);
      if (performedBy != null)
        query = query.where('performedBy', isEqualTo: performedBy);
      if (reportId != null)
        query = query.where('reportId', isEqualTo: reportId);
      if (start != null)
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        );
      if (end != null)
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(end),
        );

      // Use an async generator to capture snapshot errors and yield an empty list on error
      return (() async* {
        try {
          await for (final snapshot in query.snapshots()) {
            final items = snapshot.docs.map((doc) {
              final d = doc.data();
              return <String, dynamic>{
                'id': doc.id,
                'reportId': d['reportId'],
                'action': d['action'],
                'performedBy': d['performedBy'],
                'previousStatus': d['previousStatus'],
                'newStatus': d['newStatus'],
                'timestamp': (d['timestamp'] as Timestamp?)?.toDate(),
              };
            }).toList();

            // Do a final client-side filter for start/end in case the query couldn't be applied server-side
            final filtered = items.where((e) {
              final ts = e['timestamp'] as DateTime?;
              if (start != null && (ts == null || ts.isBefore(start)))
                return false;
              if (end != null && (ts == null || ts.isAfter(end))) return false;
              return true;
            }).toList();

            yield filtered;
          }
        } catch (e) {
          print('Error getting audit logs snapshots: $e');
          yield <Map<String, dynamic>>[];
        }
      })();
    } catch (e) {
      print('Error building audit logs query: $e');
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  // SRS Section 3.3: Status history tracking
  Future<void> _createStatusHistory(
    String reportId,
    ReportStatus status,
    String note,
  ) async {
    try {
      final firestore = _safeFirestore;
      if (firestore == null) {
        final r = _localReports[reportId];
        final history =
            (r?['statusHistory'] as List<dynamic>?) ?? <Map<String, dynamic>>[];
        history.insert(0, {
          'status': status.name,
          'note': note,
          'timestamp': DateTime.now(),
        });
        if (r != null) r['statusHistory'] = history;
        return;
      }

      await firestore
          .collection('reports')
          .doc(reportId)
          .collection('statusHistory')
          .add({
            'status': status.name,
            'note': note,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print('Error creating status history: $e');
    }
  }

  // SRS Section 3.3: Get status history for a report
  Stream<List<Map<String, dynamic>>> getStatusHistory(String reportId) {
    final firestore = _safeFirestore;
    if (firestore == null) {
      final r = _localReports[reportId];
      final hist = (r?['statusHistory'] as List<dynamic>?)
          ?.map(
            (e) => <String, dynamic>{
              'status': e['status'],
              'note': e['note'],
              'timestamp': e['timestamp'] is DateTime
                  ? e['timestamp']
                  : (e['timestamp'] as Timestamp?)?.toDate(),
            },
          )
          .toList();
      return Stream.value(hist ?? []);
    }

    return firestore
        .collection('reports')
        .doc(reportId)
        .collection('statusHistory')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return <String, dynamic>{
              'status': data['status'],
              'note': data['note'],
              'timestamp': (data['timestamp'] as Timestamp?)?.toDate(),
            };
          }).toList(),
        );
  }

  // SRS Section 6.5: Get single report by ID (for offline support)
  Future<StreetReport?> getReportById(String reportId) async {
    try {
      final firestore = _safeFirestore;
      if (firestore == null) {
        final r = _localReports[reportId];
        if (r != null) return StreetReport.fromMap(r);
        return null;
      }

      final doc = await firestore.collection('reports').doc(reportId).get();
      if (doc.exists) {
        return StreetReport.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting report: $e');
      return null;
    }
  }

  // SRS Section 6.5: Delete report (with proper authorization)
  Future<void> deleteReport(String reportId) async {
    try {
      final auth = _safeAuth;
      final firestore = _safeFirestore;
      final userEmail = auth?.currentUser?.email ?? 'demo@local';

      if (firestore == null) {
        final reportMap = _localReports[reportId];
        if (reportMap == null) throw Exception('Report not found');
        final report = StreetReport.fromMap(reportMap);

        if (report.reportedBy != userEmail) {
          throw Exception('Unauthorized to delete this report');
        }

        // remove from local store
        _localReports.remove(reportId);

        await _createAuditLog(
          reportId: reportId,
          action: 'DELETE',
          performedBy: userEmail,
          previousStatus: report.status.name,
          newStatus: 'DELETED',
        );

        return;
      }

      final reportDoc = await firestore
          .collection('reports')
          .doc(reportId)
          .get();
      if (!reportDoc.exists) throw Exception('Report not found');

      final report = StreetReport.fromFirestore(reportDoc);

      // Only allow deletion if user is the reporter or an admin
      if (report.reportedBy != auth?.currentUser?.email) {
        // Check if user is admin (would need to check role)
        throw Exception('Unauthorized to delete this report');
      }

      // Delete associated image from Cloudinary
      if (report.imageUrl != null) {
        try {
          await _cloudinaryService.deleteImage(report.imageUrl!);
        } catch (e) {
          print('Error deleting image from Cloudinary: $e');
        }
      }

      // Delete report document
      await firestore.collection('reports').doc(reportId).delete();

      // SRS Section 3.4: Log deletion
      await _createAuditLog(
        reportId: reportId,
        action: 'DELETE',
        performedBy: auth?.currentUser?.email ?? 'Unknown',
        previousStatus: report.status.name,
        newStatus: 'DELETED',
      );
    } catch (e) {
      print('Error deleting report: $e');
      rethrow;
    }
  }
}
