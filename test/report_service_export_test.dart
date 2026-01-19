import 'package:flutter_test/flutter_test.dart';
import 'package:ethio_street_fix/services/report_service.dart';

void main() {
  test(
    'ReportService.exportUserReportsJson returns valid JSON structure',
    () async {
      final json = await ReportService().exportUserReportsJson();
      expect(json, isNotNull);
      expect(json, isA<String>());
      expect(json.contains('"meta"'), isTrue);
      expect(json.contains('"reports"'), isTrue);
    },
  );
}
