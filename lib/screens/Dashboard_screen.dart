import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/report_service.dart';
import '../models/report_model.dart';
import 'report_screen.dart';
import 'report_detail_screen.dart';

// SRS Section 3.3: Citizen Dashboard for Issue Tracking
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportService = ReportService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reports"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<List<StreetReport>>(
        stream: reportService.getUserReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final err = snapshot.error.toString();
            final indexUrl = _extractIndexUrl(err);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SelectableText(
                      'Error: $err',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (indexUrl != null) ...[
                    const SizedBox(height: 12),
                    const Text('This query requires a Firestore index.'),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.link),
                      label: const Text('Create index in Firebase Console'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () => launchUrlString(indexUrl),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      indexUrl,
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ],
              ),
            );
          }

          final reports = snapshot.data ?? [];

          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.report_problem, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No reports yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the + button to report an issue',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: reports.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _showReportDetails(context, report),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Status indicator
                        Container(
                          width: 4,
                          height: 60,
                          decoration: BoxDecoration(
                            color: report.statusColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Image thumbnail
                        if (report.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              report.imageUrl!,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image),
                            ),
                          )
                        else
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.image_not_supported),
                          ),
                        const SizedBox(width: 12),
                        // Report details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      report.location,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: report.statusColor.withOpacity(
                                        0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      report.statusLabel,
                                      style: TextStyle(
                                        color: report.statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatDate(report.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("New Report"),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showReportDetails(BuildContext context, StreetReport report) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReportDetailScreen(report: report)),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String? _extractIndexUrl(String errorText) {
    final match = RegExp(
      r'https:\/\/console\.firebase\.google\.com\/\S+',
    ).firstMatch(errorText);
    return match?.group(0);
  }
}
