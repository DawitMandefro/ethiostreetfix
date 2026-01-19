import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/report_service.dart';
import '../services/notification_service.dart';
import 'report_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with AutomaticKeepAliveClientMixin {
  final NotificationService _nsvc = NotificationService();
  final ReportService _reportSvc = ReportService();
  bool _busyMarkAll = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Debug lifecycle logging to diagnose disappearing behavior
    // ignore: avoid_print
    print('NotificationsScreen: initState');
  }

  @override
  void dispose() {
    // ignore: avoid_print
    print('NotificationsScreen: dispose');
    super.dispose();
  }

  Stream<List<Map<String, dynamic>>> _buildStream() {
    // Access FirebaseAuth safely (may not be initialized in tests)
    User? auth;
    try {
      auth = FirebaseAuth.instance.currentUser;
    } catch (_) {
      auth = null;
    }

    // If user is authenticated, prefer Firestore-backed notifications via
    // NotificationService. If that fails (Firestore not configured), fall back
    // to the in-memory report service stream.
    final reportSvc = _reportSvc;
    if (auth?.email != null) {
      try {
        final nsvc = _nsvc;
        final raw = nsvc.getUserNotifications(auth!.email!).map((list) {
          // Normalize firestore-backed notifications to the shape used by UI
          return list.map((m) {
            return {
              'id': m['id'],
              'reportId': m['reportId'],
              'message': m['message'],
              'createdAt': m['timestamp'] is DateTime
                  ? (m['timestamp'] as DateTime)
                  : DateTime.tryParse(m['timestamp']?.toString() ?? ''),
              'read': m['read'] ?? false,
            };
          }).toList();
        });

        // Make the stream resilient to Firestore JS errors by converting errors
        // into an empty list event instead of allowing an uncaught zone error.
        return raw.transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stackTrace, sink) {
              // ignore: avoid_print
              print('Notifications stream error: $error\n$stackTrace');
              sink.add(<Map<String, dynamic>>[]);
            },
          ),
        );
      } catch (_) {
        // Fallthrough to local report service
      }
    }

    // Local/demo fallback
    return reportSvc.notificationsForCurrentUser().map((list) {
      return list
          .map(
            (m) => {
              'id': m['id'],
              'reportId': m['reportId'],
              'message': m['message'],
              'createdAt': m['createdAt'] is DateTime
                  ? m['createdAt']
                  : DateTime.tryParse(m['createdAt']?.toString() ?? ''),
              'read': m['read'] ?? false,
            },
          )
          .toList();
    });
  }

  String _formatRelative(dynamic dt) {
    if (dt == null) return '';
    final DateTime? date = dt is DateTime
        ? dt
        : DateTime.tryParse(dt.toString());
    if (date == null) return dt.toString();
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _markAsRead(String id) async {
    final auth = FirebaseAuth.instance.currentUser;
    try {
      if (auth?.email != null) {
        // Prefer the Firestore-backed notification service
        await _nsvc.markAsRead(id);
      } else {
        await _reportSvc.markNotificationAsRead(id);
      }
    } catch (e) {
      // fallback to report service for local/demo mode
      try {
        await _reportSvc.markNotificationAsRead(id);
      } catch (_) {}
    }
  }

  Future<void> _markAllRead() async {
    final auth = FirebaseAuth.instance.currentUser;
    setState(() => _busyMarkAll = true);
    try {
      if (auth?.email != null) {
        await _nsvc.markAllAsRead(auth!.email!);
      } else {
        await _reportSvc.markAllNotificationsAsRead(
          auth?.email ?? 'demo@local',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busyMarkAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for AutomaticKeepAliveClientMixin
    final stream = _buildStream();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: _busyMarkAll ? null : _markAllRead,
            icon: _busyMarkAll
                ? const CircularProgressIndicator.adaptive(strokeWidth: 2)
                : const Icon(Icons.mark_email_read),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No notifications',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final read = n['read'] == true;
              final createdAt = n['createdAt'];

              return Dismissible(
                key: ValueKey(n['id']),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.green,
                  child: const Icon(Icons.mark_email_read, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await _markAsRead(n['id']);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marked as read')),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: read ? Colors.grey.shade300 : Colors.green,
                    child: Icon(
                      read
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: read ? Colors.black54 : Colors.white,
                    ),
                  ),
                  title: Text(
                    n['message'] ?? 'Update',
                    style: TextStyle(
                      fontWeight: read ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(_formatRelative(createdAt)),
                  trailing: IconButton(
                    icon: Icon(
                      read
                          ? Icons.check_circle_outline
                          : Icons.mark_email_unread,
                    ),
                    tooltip: read ? 'Already read' : 'Mark as read',
                    onPressed: read
                        ? null
                        : () async {
                            await _markAsRead(n['id']);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Marked as read')),
                            );
                          },
                  ),
                  onTap: () async {
                    // Mark as read and navigate to report detail if present
                    await _markAsRead(n['id']);
                    if (!mounted) return;
                    if (n['reportId'] != null) {
                      try {
                        final report = await ReportService().getReportById(
                          n['reportId'] as String,
                        );
                        if (report != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReportDetailScreen(report: report),
                            ),
                          );
                        }
                      } catch (e) {
                        // ignore: avoid_print
                        print(
                          'Error opening report detail from notification: $e',
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
