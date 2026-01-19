import 'package:flutter_test/flutter_test.dart';
import 'package:ethio_street_fix/services/report_service.dart';

void main() {
  test('exportAllReportsJson returns valid json in local mode', () async {
    final svc = ReportService();

    // Create two local reports
    final id1 = await svc.submitReport(
      title: 'r1',
      description: 'd1',
      location: 'loc1',
      latitude: 8.9,
      longitude: 38.7,
    );
    final id2 = await svc.submitReport(
      title: 'r2',
      description: 'd2',
      location: 'loc2',
      latitude: 8.8,
      longitude: 38.6,
    );

    final json = await svc.exportAllReportsJson();
    expect(json, contains('"reports"'));
    expect(json, contains(id1));
    expect(json, contains(id2));
  });
}
