import 'package:flutter_test/flutter_test.dart';
import 'package:ethio_street_fix/services/report_service.dart';
import 'package:ethio_street_fix/models/report_model.dart';

void main() {
  test(
    'notifications stream emits initial seed and update in local mode',
    () async {
      final svc = ReportService();

      // Create a local report (firestore will be unavailable in test env)
      final id = await svc.submitReport(
        title: 'test',
        description: 'desc',
        location: 'loc',
        latitude: 9.0,
        longitude: 38.0,
      );
      expect(id, isNotNull);

      final events = <List<Map<String, dynamic>>>[];
      final sub = svc.notificationsForCurrentUser().listen((e) {
        events.add(e);
      });

      // Trigger the status update which should emit a notification. We
      // subscribe before updating to ensure we observe both the seed and
      // the subsequent update.
      await svc.updateReportStatus(
        reportId: id!,
        newStatus: ReportStatus.inProgress,
      );

      // wait up to 1s for two emissions (initial seed + update)
      const timeout = Duration(seconds: 1);
      final stopwatch = Stopwatch()..start();
      while (events.length < 2 && stopwatch.elapsed < timeout) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      await sub.cancel();

      // At least two emissions: initial seed and the update
      expect(events.length, greaterThanOrEqualTo(2));
      final flattened = events.expand((e) => e).toList();
      expect(flattened.any((n) => n['reportId'] == id), isTrue);
    },
  );
}
