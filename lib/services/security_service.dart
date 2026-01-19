import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// SRS Section 6.2: Security Requirements - Data encryption and protection
// SRS Section 6.3: Privacy Requirements - Location data protection
class SecurityService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // SRS Section 6.2: Encrypt sensitive data at rest
  static Future<void> storeSecureData(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      print('Error storing secure data: $e');
      rethrow;
    }
  }

  // SRS Section 6.2: Retrieve encrypted data
  static Future<String?> getSecureData(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      print('Error reading secure data: $e');
      return null;
    }
  }

  // SRS Section 6.2: Delete secure data
  static Future<void> deleteSecureData(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      print('Error deleting secure data: $e');
    }
  }

  // SRS Section 6.2: Hash sensitive information
  static String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // SRS Section 6.3: Sanitize location data for privacy
  static Map<String, dynamic> sanitizeLocationData({
    required double latitude,
    required double longitude,
    bool anonymize = false,
  }) {
    if (anonymize) {
      // Round to reduce precision (privacy protection)
      return {
        'latitude': latitude.toStringAsFixed(2),
        'longitude': longitude.toStringAsFixed(2),
        'precision': 'reduced',
      };
    }
    return {'latitude': latitude, 'longitude': longitude, 'precision': 'high'};
  }

  // SRS Section 6.2: Validate data integrity
  static bool validateDataIntegrity(String data, String hash) {
    return hashData(data) == hash;
  }

  /// Placeholder for encrypting payloads before transmission.
  /// Currently a no-op for development; replace with real encryption and
  /// secure key management before production (defense-in-depth requirement).
  static Map<String, dynamic> encryptPayload(Map<String, dynamic> payload) {
    // TODO(production): implement AES/GCM or public-key encryption here.
    return payload;
  }

  // SRS Section 6.2: Clear all secure storage (logout)
  static Future<void> clearAllSecureData() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      print('Error clearing secure data: $e');
    }
  }

  // SRS Section 6.2: Check if HTTPS is being used (Firebase uses HTTPS by default)
  static bool isSecureConnection(String url) {
    return url.startsWith('https://');
  }
}
