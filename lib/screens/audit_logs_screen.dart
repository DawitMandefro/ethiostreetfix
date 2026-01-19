import 'package:flutter/material.dart';
import '../services/report_service.dart';
import 'report_detail_screen.dart';

class AuditLogsScreen extends StatefulWidget {
  final String? performedBy;
  const AuditLogsScreen({super.key, this.performedBy});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final svc = ReportService();
  final reportIdController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  // Applied filters
  String? _appliedReportId;
  DateTime? _appliedStart;
  DateTime? _appliedEnd;

  @override
  void dispose() {
    reportIdController.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => endDate = picked);
  }

  void _applyFilters() {
    setState(() {
      _appliedReportId = reportIdController.text.trim().isEmpty
          ? null
          : reportIdController.text.trim();
      _appliedStart = startDate;
      _appliedEnd = endDate != null
          ? DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59)
          : null;
    });
  }

  void _clearFilters() {
    setState(() {
      reportIdController.clear();
      startDate = null;
      endDate = null;
      _appliedReportId = null;
      _appliedStart = null;
      _appliedEnd = null;
    });
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final stream = svc.getAuditLogs(
      performedBy: widget.performedBy,
      reportId: _appliedReportId,
      start: _appliedStart,
      end: _appliedEnd,
    );

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: Text(
          widget.performedBy == null ? 'Audit Logs' : 'My Audit Logs',
        ),
        actions: [
          IconButton(
            tooltip: 'Clear filters',
            icon: const Icon(Icons.clear_all),
            onPressed: _clearFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: reportIdController,
                        decoration: const InputDecoration(
                          labelText: 'Report ID',
                          hintText: 'Filter by report id (optional)',
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _applyFilters,
                      child: const Text('Apply'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickStart,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start date',
                          ),
                          child: Text(_formatDate(startDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: _pickEnd,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End date',
                          ),
                          child: Text(_formatDate(endDate)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (_appliedReportId != null)
                      Chip(label: Text('report: ${_appliedReportId!}')),
                    if (_appliedStart != null)
                      Chip(label: Text('from: ${_formatDate(_appliedStart)}')),
                    if (_appliedEnd != null)
                      Chip(label: Text('to: ${_formatDate(_appliedEnd)}')),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('No audit log entries'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    final ts = e['timestamp'] as DateTime?;
                    final subtitle =
                        '${e['performedBy'] ?? ''} • ${ts != null ? '${ts.day}/${ts.month}/${ts.year} ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}' : ''}';

                    return ListTile(
                      leading: const Icon(Icons.security),
                      title: Text('${e['action']} — ${e['reportId'] ?? ''}'),
                      subtitle: Text(subtitle),
                      onTap: () async {
                        final reportId = e['reportId'] as String?;
                        if (reportId != null) {
                          try {
                            final report = await svc.getReportById(reportId);
                            if (report != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReportDetailScreen(report: report),
                                ),
                              );
                            }
                          } catch (err) {
                            // ignore: avoid_print
                            print('Error loading report: $err');
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
