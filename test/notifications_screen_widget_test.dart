import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ethio_street_fix/screens/notifications_screen.dart';
import 'package:ethio_street_fix/services/report_service.dart';
import 'package:ethio_street_fix/models/report_model.dart';

void main() {
  testWidgets('NotificationsScreen shows local notifications', (tester) async {
    // Create a local report and update status to emit a notification
    final svc = ReportService();
    final id = await svc.submitReport(
      title: 'widget test report',
      description: 'desc',
      location: 'loc',
      latitude: 1.0,
      longitude: 1.0,
    );

    // Build UI
    await tester.pumpWidget(MaterialApp(home: const NotificationsScreen()));

    // Trigger a status update which should emit a notification in local mode
    await svc.updateReportStatus(
      reportId: id!,
      newStatus: ReportStatus.inProgress,
    );

    // Allow the stream to deliver
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Expect at least one notification message visible
    expect(find.textContaining('Your report has been updated'), findsOneWidget);
  });
}
