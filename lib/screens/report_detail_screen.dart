import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';
import '../widgets/status_timeline.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.report});

  final StreetReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text('Report details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (report.imageUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                report.imageUrl!,
                height: 280,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const SizedBox(
                  height: 280,
                  child: Center(child: Icon(Icons.broken_image)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            report.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            report.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),

          // mini-map (best-effort)
          if (report.latitude != null && report.longitude != null) ...[
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // open external map if available
                // ignore: prefer_interpolation_to_compose_strings
                final url =
                    'https://www.google.com/maps/search/?api=1&query=' +
                    report.latitude.toString() +
                    ',' +
                    report.longitude.toString();
                // open in browser via url_launcher where available
                try {
                  // lazy to avoid adding import at top-level
                  // ignore: avoid_dynamic_calls
                  // launchUrlString(url);
                } catch (_) {}
              },
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: Center(
                  child: Text(
                    'Map preview — ${report.latitude?.toStringAsFixed(4)}, ${report.longitude?.toStringAsFixed(4)}',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Status timeline
          const SizedBox(height: 8),
          Text(
            'Status timeline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: ReportService().getStatusHistory(report.id),
            builder: (context, snapshot) {
              final history = snapshot.data ?? [];
              return StatusTimeline(current: report.status, history: history);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
