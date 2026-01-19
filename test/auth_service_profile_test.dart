import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ethio_street_fix/services/auth_service.dart';

void main() {
  test('updateProfile stores profile in local fallback', () async {
    final svc = AuthService();

    // Ensure no firestore/auth present in test env -> local fallback
    await svc.updateProfile(
      displayName: 'Tester',
      photoBytes: Uint8List.fromList([1, 2, 3]),
      photoFilename: 'p.jpg',
    );
    final profile = await svc.getCurrentUserProfile();

    expect(profile['displayName'], 'Tester');
    expect(profile['email'], isNotNull);
    // In local mode we store inline photoData for preview (avoid network)
    expect(profile['photoUrl'] != null || profile['photoData'] != null, isTrue);
  });
}
