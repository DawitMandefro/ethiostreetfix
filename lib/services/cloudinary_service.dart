import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:crypto/crypto.dart';

/// Cloudinary service for image upload and management
/// SRS Section 6.1: Image optimization with Cloudinary
class CloudinaryService {
  // Cloudinary credentials
  // Get these from https://console.cloudinary.com/
  // For production, consider using environment variables or secure storage
  static const String _cloudName = 'dowlfgxza';
  static const String _apiKey = '749414511138685';
  // API Secret - Reveal the full secret in Cloudinary Console and update below
  // Only needed for deletion operations. For uploads, use unsigned upload preset.
  static const String _apiSecret =
      'NTq0k1iKOu5k...'; // TODO: Replace with full API secret
  // Upload preset for unsigned uploads (recommended for client-side)
  // Create one at: https://console.cloudinary.com/settings/upload
  // Set signing mode to "Unsigned" and name it (e.g., 'ethio_street_fix_unsigned')
  static const String _uploadPreset =
      'ethio_street_fix_unsigned'; // TODO: Create this preset in Cloudinary

  /// Upload image file-like object to Cloudinary (mobile helper)
  /// Accepts objects that implement `readAsBytes()` such as `XFile` or `File`.
  /// Returns the secure URL of the uploaded image
  Future<String> uploadImage(dynamic imageFileLike, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = 'ethio_street_fix/reports/$userId/$timestamp';

      // Read bytes from the provided object (XFile or File both support this)
      final Uint8List bytes = await imageFileLike.readAsBytes();

      return await _uploadBytes(bytes, publicId, 'image/jpeg');
    } catch (e) {
      print('Error uploading image to Cloudinary: $e');
      rethrow;
    }
  }

  /// Upload image bytes to Cloudinary (Web/Mobile)
  /// Returns the secure URL of the uploaded image
  Future<String> uploadImageBytes(
    Uint8List imageBytes,
    String userId,
    String originalFileName,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = originalFileName.split('.').last.toLowerCase();
      final publicId = 'ethio_street_fix/reports/$userId/$timestamp';

      // Determine content type
      String contentType = 'image/jpeg';
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'gif') {
        contentType = 'image/gif';
      } else if (extension == 'webp') {
        contentType = 'image/webp';
      }

      return await _uploadBytes(imageBytes, publicId, contentType);
    } catch (e) {
      print('Error uploading image bytes to Cloudinary: $e');
      rethrow;
    }
  }

  /// Internal method to upload bytes to Cloudinary
  Future<String> _uploadBytes(
    Uint8List bytes,
    String publicId,
    String contentType,
  ) async {
    try {
      // Use unsigned upload with upload preset (recommended for client-side)
      // Or use signed upload with API secret (for server-side)

      // Check if upload preset is configured
      if (_uploadPreset.isNotEmpty && _uploadPreset != 'YOUR_UPLOAD_PRESET') {
        // Unsigned upload using upload preset
        return await _unsignedUpload(bytes, publicId, contentType);
      } else {
        // If upload preset is not set, throw an error asking user to configure upload preset
        throw Exception(
          'Upload preset not configured. Please create an unsigned upload preset named "ethio_street_fix_unsigned" in Cloudinary Console at https://console.cloudinary.com/settings/upload',
        );
      }
    } catch (e) {
      print('Error in _uploadBytes: $e');
      rethrow;
    }
  }

  /// Unsigned upload using upload preset (client-side safe)
  Future<String> _unsignedUpload(
    Uint8List bytes,
    String publicId,
    String contentType,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add upload preset
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['public_id'] = publicId;

      // Add folder for organization
      request.fields['folder'] = 'ethio_street_fix/reports';

      // Add file - ensure filename does not contain '/' to avoid issues
      final safeFilename = '${publicId.split('/').last}.jpg';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: safeFilename,
          contentType: _getMediaType(contentType),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['secure_url'] as String;
      } else {
        throw Exception(
          'Cloudinary upload failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error in unsigned upload: $e');
      rethrow;
    }
  }

  /// Get content type as MediaType for HTTP multipart
  MediaType _getMediaType(String contentType) {
    try {
      return MediaType.parse(contentType);
    } catch (_) {
      // Fallback
      return MediaType('image', 'jpeg');
    }
  }

  /// Delete image from Cloudinary using public ID or URL
  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract public ID from Cloudinary URL
      final publicId = _extractPublicId(imageUrl);
      if (publicId == null) {
        print('Could not extract public ID from URL: $imageUrl');
        return;
      }

      // Check if API secret is configured
      if (_apiSecret.isEmpty ||
          _apiSecret == 'YOUR_API_SECRET' ||
          _apiSecret.endsWith('...')) {
        print(
          'API Secret not fully configured. Image deletion requires the full API secret.',
        );
        print(
          'Please reveal the full API secret in Cloudinary Console and update _apiSecret in cloudinary_service.dart',
        );
        return;
      }

      // Generate signature for deletion
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final signature = _generateSignature(publicId, timestamp);

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy',
      );

      final response = await http.post(
        uri,
        body: {
          'public_id': publicId,
          'timestamp': timestamp,
          'api_key': _apiKey,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['result'] == 'ok') {
          print('Image deleted successfully from Cloudinary');
        } else {
          print('Failed to delete image: ${responseData['result']}');
        }
      } else {
        print(
          'Error deleting image: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error deleting image from Cloudinary: $e');
      // Don't rethrow - deletion failure shouldn't block the main operation
    }
  }

  /// Extract public ID from Cloudinary URL
  /// Cloudinary URL formats:
  /// - https://res.cloudinary.com/{cloud_name}/image/upload/{transformations}/{public_id}.{format}
  /// - https://res.cloudinary.com/{cloud_name}/image/upload/v{version}/{public_id}.{format}
  String? _extractPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;

      // Find '/upload/' in path
      final uploadIndex = path.indexOf('/upload/');
      if (uploadIndex == -1) {
        print('Invalid Cloudinary URL: upload path not found');
        return null;
      }

      // Get everything after '/upload/'
      var pathAfterUpload = path.substring(
        uploadIndex + 8,
      ); // 8 = length of '/upload/'

      // Remove version prefix if present (v1234567890/)
      if (pathAfterUpload.startsWith('v') && pathAfterUpload.contains('/')) {
        final firstSlash = pathAfterUpload.indexOf('/');
        pathAfterUpload = pathAfterUpload.substring(firstSlash + 1);
      }

      // Remove transformation parameters
      // Transformations can be in the format: w_500,h_300,c_fill/ or f_auto,q_auto/
      // They appear before the actual public_id
      // The public_id starts after the last transformation parameter
      // We'll look for patterns and extract the actual file path

      // Split by '/' and find the last segment which should be the filename
      final segments = pathAfterUpload.split('/');
      if (segments.isEmpty) {
        return null;
      }

      // The last segment is the filename with extension
      final filename = segments.last;
      final dotIndex = filename.lastIndexOf('.');
      final filenameWithoutExt = dotIndex != -1
          ? filename.substring(0, dotIndex)
          : filename;

      // Reconstruct public ID with folder path
      // Remove the filename from segments
      final folderSegments = segments.sublist(0, segments.length - 1);

      // Filter out transformation segments (they typically contain underscores and numbers)
      // Public ID segments are usually simple folder names
      final publicIdSegments = <String>[];
      for (var segment in folderSegments) {
        // Skip transformation segments (they usually have format like "w_500" or "f_auto,q_auto")
        if (!segment.contains('_') ||
            (!segment.contains('w_') &&
                !segment.contains('h_') &&
                !segment.contains('c_') &&
                !segment.contains('f_') &&
                !segment.contains('q_'))) {
          publicIdSegments.add(segment);
        }
      }

      // Add filename
      publicIdSegments.add(filenameWithoutExt);

      return publicIdSegments.join('/');
    } catch (e) {
      print('Error extracting public ID from URL: $url - $e');
      return null;
    }
  }

  /// Generate signature for Cloudinary API calls
  String _generateSignature(String publicId, String timestamp) {
    final params = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
    final bytes = utf8.encode(params);
    final hash = sha1.convert(bytes);
    return hash.toString();
  }
}
