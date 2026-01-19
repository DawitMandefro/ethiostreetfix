import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';
import '../services/notification_service.dart';

// SRS Section 3.4: Authority Issue Management Dashboard
class AuthorityDashboard extends StatefulWidget {
  const AuthorityDashboard({super.key});

  @override
  State<AuthorityDashboard> createState() => _AuthorityDashboardState();
}

class _AuthorityDashboardState extends State<AuthorityDashboard> {
  final ReportService _reportService = ReportService();
  NotificationService? _notificationService;
  ReportStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    // Defer creation of services that may depend on platform channels (Firebase)
    try {
      _notificationService = NotificationService();
    } catch (e) {
      // ignore: avoid_print
      print('NotificationService unavailable: $e');
      _notificationService = null;
    }
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // Trigger a rebuild; stream will update automatically when backend changes.
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Authority Dashboard"),
          backgroundColor: Colors.green,
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: "All", icon: Icon(Icons.list)),
              Tab(text: "Pending", icon: Icon(Icons.hourglass_empty)),
              Tab(text: "In Progress", icon: Icon(Icons.work)),
              Tab(text: "Fixed", icon: Icon(Icons.check_circle)),
            ],
            onTap: (index) {
              setState(() {
                switch (index) {
                  case 0:
                    _statusFilter = null;
                    break;
                  case 1:
                    _statusFilter = ReportStatus.pending;
                    break;
                  case 2:
                    _statusFilter = ReportStatus.inProgress;
                    break;
                  case 3:
                    _statusFilter = ReportStatus.fixed;
                    break;
                }
              });
            },
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await _refresh();
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Refreshed')));
            }
          },
          label: const Text('Refresh'),
          icon: const Icon(Icons.refresh),
          backgroundColor: Colors.green,
        ),
        body: StreamBuilder<List<StreetReport>>(
          stream: _reportService.getAllReports(statusFilter: _statusFilter),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                  ],
                ),
              );
            }

            final reports = snapshot.data ?? [];

            // Apply search filter
            final filtered = reports.where((r) {
              final q = _searchQuery.toLowerCase();
              if (q.isEmpty) return true;
              return r.title.toLowerCase().contains(q) ||
                  r.location.toLowerCase().contains(q) ||
                  (r.reportedBy ?? '').toLowerCase().contains(q);
            }).toList();

            // Summary counts
            final total = reports.length;
            final pending = reports
                .where((r) => r.status == ReportStatus.pending)
                .length;
            final inProgress = reports
                .where((r) => r.status == ReportStatus.inProgress)
                .length;
            final fixed = reports
                .where((r) => r.status == ReportStatus.fixed)
                .length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by title, location or reporter',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Summary chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _summaryChip(
                              'All',
                              total,
                              Colors.blue,
                              _statusFilter == null,
                            ),
                            const SizedBox(width: 8),
                            _summaryChip(
                              'Pending',
                              pending,
                              Colors.orange,
                              _statusFilter == ReportStatus.pending,
                            ),
                            const SizedBox(width: 8),
                            _summaryChip(
                              'In Progress',
                              inProgress,
                              Colors.purple,
                              _statusFilter == ReportStatus.inProgress,
                            ),
                            const SizedBox(width: 8),
                            _summaryChip(
                              'Fixed',
                              fixed,
                              Colors.green,
                              _statusFilter == ReportStatus.fixed,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: filtered.isEmpty
                          ? ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              children: [
                                SizedBox(height: 120),
                                const Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? (_statusFilter == null
                                            ? 'No reports found'
                                            : 'No ${_statusFilter?.name} reports')
                                      : 'No results for "$_searchQuery"',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final report = filtered[index];
                                return _buildReportCard(report);
                              },
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summaryChip(String title, int count, Color color, bool selected) {
    return InputChip(
      label: Text('$title ($count)'),
      backgroundColor: selected
          ? color.withOpacity(0.15)
          : Colors.grey.shade100,
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      onPressed: () {
        setState(() {
          switch (title) {
            case 'All':
              _statusFilter = null;
              break;
            case 'Pending':
              _statusFilter = ReportStatus.pending;
              break;
            case 'In Progress':
              _statusFilter = ReportStatus.inProgress;
              break;
            case 'Fixed':
              _statusFilter = ReportStatus.fixed;
              break;
          }
        });
      },
    );
  }

  Widget _buildReportCard(StreetReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail or initials
                  if (report.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        report.imageUrl!,
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 88,
                          height: 88,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.broken_image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          (report.title.isNotEmpty ? report.title[0] : '?')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                report.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text(report.statusLabel),
                              backgroundColor: report.statusColor.withOpacity(
                                0.15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          report.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                report.location,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reported: ${_formatDate(report.createdAt)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Row(
                    children: [
                      if (report.status != ReportStatus.fixed &&
                          report.status != ReportStatus.rejected) ...[
                        ElevatedButton.icon(
                          onPressed: () =>
                              _updateStatus(report, ReportStatus.inProgress),
                          icon: const Icon(Icons.play_arrow, size: 16),
                          label: const Text('Start'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _updateStatus(report, ReportStatus.fixed),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Fix'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _updateStatus(report, ReportStatus.rejected),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SRS Section 3.4: Update report status with audit logging
  Future<void> _updateStatus(
    StreetReport report,
    ReportStatus newStatus,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('User not authenticated')));
        return;
      }

      // SRS Section 3.4: Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Update Status to ${newStatus.name}?'),
          content: Text(
            'This action will be logged in the audit trail for accountability.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // SRS Section 3.4: Update status with audit logging
      await _reportService.updateReportStatus(
        reportId: report.id,
        newStatus: newStatus,
        resolvedBy: user.email,
      );

      // SRS Section 3.3: Send notification to reporter
      if (report.reportedBy != null) {
        await _notificationService?.notifyStatusUpdate(
          reportId: report.id,
          userEmail: report.reportedBy!,
          newStatus: newStatus,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // SRS Section 3.4: Show detailed report view
  void _showReportDetails(StreetReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar with close/back button to return to previous page
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(report.statusLabel),
                    backgroundColor: report.statusColor.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (report.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    report.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 100),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildDetailRow('Description', report.description),
              _buildDetailRow('Location', report.location),
              if (report.latitude != null && report.longitude != null)
                _buildDetailRow(
                  'GPS Coordinates',
                  '${report.latitude}, ${report.longitude}',
                ),
              if (report.reportedBy != null)
                _buildDetailRow('Reported By', report.reportedBy!),
              _buildDetailRow('Created', _formatDate(report.createdAt)),
              if (report.updatedAt != null)
                _buildDetailRow('Last Updated', _formatDate(report.updatedAt!)),
              if (report.resolvedBy != null)
                _buildDetailRow('Resolved By', report.resolvedBy!),
              const SizedBox(height: 20),
              // SRS Section 3.3: Status history
              const Text(
                'Status History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _reportService.getStatusHistory(report.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final history = snapshot.data ?? [];
                  if (history.isEmpty) {
                    return const Text('No status history available');
                  }
                  return Column(
                    children: history.map((entry) {
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(entry['status'] ?? 'Unknown'),
                        subtitle: Text(entry['note'] ?? ''),
                        trailing: Text(
                          entry['timestamp'] != null
                              ? _formatDate(entry['timestamp'] as DateTime)
                              : '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
