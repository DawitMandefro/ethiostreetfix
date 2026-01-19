import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../models/user_role.dart';
import '../models/report_model.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';

// SRS Section 2.3: System Administrator Dashboard
// SRS Section 3.1: RBAC - Administrator access
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("System Administration"),
          backgroundColor: Colors.red,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: "Overview", icon: Icon(Icons.dashboard)),
              Tab(
                text: "Manage Reports",
                icon: Icon(Icons.admin_panel_settings),
              ),
              Tab(text: "Audit Logs", icon: Icon(Icons.security)),
              Tab(text: "User Management", icon: Icon(Icons.people)),
              Tab(text: "System Stats", icon: Icon(Icons.analytics)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OverviewTab(),
            _ManageReportsTab(),
            _AuditLogsTab(),
            _UserManagementTab(),
            _SystemStatsTab(),
          ],
        ),
      ),
    );
  }
}

// SRS Section 2.3: Overview tab for administrators
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;
        final pendingCount = reports
            .where((doc) => doc['status'] == 'pending')
            .length;
        final inProgressCount = reports
            .where((doc) => doc['status'] == 'inProgress')
            .length;
        final fixedCount = reports
            .where((doc) => doc['status'] == 'fixed')
            .length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'System Overview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Total Reports',
                      value: reports.length.toString(),
                      icon: Icons.report,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Pending',
                      value: pendingCount.toString(),
                      icon: Icons.hourglass_empty,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'In Progress',
                      value: inProgressCount.toString(),
                      icon: Icons.work,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Fixed',
                      value: fixedCount.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final json = await ReportService().exportAllReportsJson();
                      if (!context.mounted) return;
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Exported Reports (JSON)'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: SingleChildScrollView(
                              child: SelectableText(json),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                            TextButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: json));
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied JSON to clipboard'),
                                  ),
                                );
                              },
                              child: const Text('Copy'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export All Reports'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('audit_logs')
                    .orderBy('timestamp', descending: true)
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final logs = snapshot.data!.docs;
                  if (logs.isEmpty) {
                    return const Text('No recent activity');
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index].data() as Map<String, dynamic>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.security),
                          title: Text(log['action'] ?? 'Unknown Action'),
                          subtitle: Text(
                            'By: ${log['performedBy'] ?? 'Unknown'}\n'
                            'Report: ${log['reportId'] ?? 'N/A'}',
                          ),
                          trailing: Text(
                            log['timestamp'] != null
                                ? _formatTimestamp(
                                    log['timestamp'] as Timestamp,
                                  )
                                : '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}

// SRS Section 3.4: Audit Logs Tab - View all audit logs
class _AuditLogsTab extends StatelessWidget {
  const _AuditLogsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final logs = snapshot.data!.docs;
        if (logs.isEmpty) {
          return const Center(child: Text('No audit logs found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.security, color: Colors.red),
                title: Text(log['action'] ?? 'Unknown Action'),
                subtitle: Text(
                  'By: ${log['performedBy'] ?? 'Unknown'} • '
                  '${_formatTimestamp(log['timestamp'] as Timestamp?)}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Report ID', log['reportId'] ?? 'N/A'),
                        _buildDetailRow(
                          'Previous Status',
                          log['previousStatus'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'New Status',
                          log['newStatus'] ?? 'N/A',
                        ),
                        _buildDetailRow(
                          'Timestamp',
                          log['timestamp'] != null
                              ? _formatTimestamp(log['timestamp'] as Timestamp)
                              : 'N/A',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// SRS Section 3.1: User Management Tab - Manage user roles
class _UserManagementTab extends StatelessWidget {
  const _UserManagementTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('email')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final users = snapshot.data!.docs;
        if (users.isEmpty) {
          return const Center(child: Text('No users found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index].data() as Map<String, dynamic>;
            final userId = users[index].id;
            final email = user['email'] ?? 'Unknown';
            final roleStr = user['role'] ?? 'citizen';
            final role = _parseRole(roleStr);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(child: Text(email[0].toUpperCase())),
                title: Text(email),
                subtitle: Text('Role: ${role.label}'),
                trailing: DropdownButton<UserRole>(
                  value: role,
                  items: UserRole.values.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r.label));
                  }).toList(),
                  onChanged: (newRole) {
                    if (newRole != null) {
                      _updateUserRole(context, userId, newRole);
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  UserRole _parseRole(String roleStr) {
    switch (roleStr) {
      case 'authority':
        return UserRole.authority;
      case 'administrator':
        return UserRole.administrator;
      default:
        return UserRole.citizen;
    }
  }

  Future<void> _updateUserRole(
    BuildContext context,
    String userId,
    UserRole newRole,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update cache if it's the current user
      if (FirebaseAuth.instance.currentUser?.uid == userId) {
        await AuthService().setRole(newRole);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User role updated to ${newRole.label}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// SRS Section 6.2: System Statistics Tab
class _SystemStatsTab extends StatelessWidget {
  const _SystemStatsTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'System Statistics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .snapshots(),
            builder: (context, reportsSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, usersSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('audit_logs')
                        .snapshots(),
                    builder: (context, logsSnapshot) {
                      if (!reportsSnapshot.hasData ||
                          !usersSnapshot.hasData ||
                          !logsSnapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final reportCount = reportsSnapshot.data!.docs.length;
                      final userCount = usersSnapshot.data!.docs.length;
                      final logCount = logsSnapshot.data!.docs.length;

                      return Column(
                        children: [
                          _StatCard(
                            title: 'Total Users',
                            value: userCount.toString(),
                            icon: Icons.people,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          _StatCard(
                            title: 'Total Reports',
                            value: reportCount.toString(),
                            icon: Icons.report,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          _StatCard(
                            title: 'Audit Log Entries',
                            value: logCount.toString(),
                            icon: Icons.security,
                            color: Colors.red,
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Admin Manage Reports tab
class _ManageReportsTab extends StatefulWidget {
  const _ManageReportsTab({super.key});

  @override
  State<_ManageReportsTab> createState() => _ManageReportsTabState();
}

class _ManageReportsTabState extends State<_ManageReportsTab> {
  final ReportService _reportService = ReportService();
  ReportStatus? _filter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<ReportStatus?>(
                  value: _filter,
                  hint: const Text('Filter by status'),
                  isExpanded: true,
                  items:
                      <ReportStatus?>[
                            null,
                            ReportStatus.pending,
                            ReportStatus.inProgress,
                            ReportStatus.fixed,
                          ]
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s?.name ?? 'All'),
                            ),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  // Quick export of filtered reports
                  final json = await _reportService.exportAllReportsJson();
                  if (!context.mounted) return;
                  await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Exported (JSON)'),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: SingleChildScrollView(
                          child: SelectableText(json),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Export'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<StreetReport>>(
            stream: _reportService.getAllReports(statusFilter: _filter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final reports = snapshot.data ?? [];
              if (reports.isEmpty) {
                return const Center(child: Text('No reports'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final r = reports[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: r.statusColor,
                      child: Text(r.statusLabel[0]),
                    ),
                    title: Text(r.title),
                    subtitle: Text(r.location),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete report?'),
                              content: const Text(
                                'This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await _reportService.deleteReport(r.id);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report deleted')),
                            );
                          }
                        } else if (action == 'view') {
                          Navigator.of(context).pushNamed('/report/${r.id}');
                        } else if (action == 'start') {
                          await _reportService.updateReportStatus(
                            reportId: r.id,
                            newStatus: ReportStatus.inProgress,
                          );
                        } else if (action == 'fix') {
                          await _reportService.updateReportStatus(
                            reportId: r.id,
                            newStatus: ReportStatus.fixed,
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'view', child: Text('View')),
                        const PopupMenuItem(
                          value: 'start',
                          child: Text('Set In Progress'),
                        ),
                        const PopupMenuItem(
                          value: 'fix',
                          child: Text('Set Fixed'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
