import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../services/report_service.dart';
import '../services/network_service.dart';
import '../services/security_service.dart';

// SRS Section 3.2: Issue Reporting Screen with image and GPS location
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  Uint8List? _imageBytes; // Unified image bytes for web & mobile
  XFile? _pickedFile; // Store XFile for cross-platform support
  String _locationMessage = "Location not set";
  double? _latitude;
  double? _longitude;
  bool _isUploading = false;
  bool _isGettingLocation = false;
  bool _anonymizeLocation = false; // SRS Section 6.3: Privacy option

  final ReportService _reportService = ReportService();
  final NetworkService _networkService = NetworkService();
  NetworkStatus _networkStatus = NetworkStatus.offline;

  @override
  void initState() {
    super.initState();
    _checkNetworkStatus();
    _networkService.networkStatusStream.listen((status) {
      if (mounted) {
        setState(() => _networkStatus = status);
      }
    });
  }

  Future<void> _checkNetworkStatus() async {
    final status = await _networkService.getCurrentStatus();
    if (mounted) {
      setState(() => _networkStatus = status);
    }
  }

  // SRS Section 3.2: Capture image using mobile device camera
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();

      // On web, camera might not be available, so allow gallery selection
      final pickedFile = await picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 70, // SRS Section 6.1: Performance optimization
        maxWidth: 1920, // Limit image size for bandwidth optimization
      );

      if (pickedFile != null) {
        _pickedFile = pickedFile;
        // Read bytes on all platforms for a unified rendering/upload path
        final bytes = await pickedFile.readAsBytes();
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Image picker error: $e")));
      }
    }
  }

  // SRS Section 3.2: Attach GPS-based location data
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Please enable GPS Location Services"),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location permissions denied")),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Location permissions permanently denied. Please enable in settings.",
              ),
            ),
          );
        }
        return;
      }

      // SRS Section 3.2: Get high-accuracy GPS position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // SRS Section 6.3: Apply privacy controls if requested
      final locationData = _anonymizeLocation
          ? SecurityService.sanitizeLocationData(
              latitude: position.latitude,
              longitude: position.longitude,
              anonymize: true,
            )
          : SecurityService.sanitizeLocationData(
              latitude: position.latitude,
              longitude: position.longitude,
              anonymize: false,
            );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationMessage =
            "Lat: ${locationData['latitude']}, Long: ${locationData['longitude']}";
        _locationController.text = _locationMessage;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Location Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  // SRS Section 3.2: Submit report with encryption and secure transmission
  // SRS Section 6.5: Network resilience with retry mechanism
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if ((_imageBytes == null) || _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please take a photo first!")),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please capture GPS location first!")),
      );
      return;
    }

    // SRS Section 6.5: Check network availability
    final isOnline = await _networkService.isOnline();
    if (!isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No internet connection. Please check your network and try again.",
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      // SRS Section 6.2: Secure data transmission (Firebase uses HTTPS/TLS)
      // SRS Section 6.5: Retry mechanism for network operations
      final reportId = await RetryHandler.retry(
        operation: () async {
          // Unified path: we already read image bytes into `_imageBytes` and
          // keep the original XFile in `_pickedFile` — submitReport handles both.
          return await _reportService.submitReport(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            location: _locationController.text.trim().isEmpty
                ? _locationMessage
                : _locationController.text.trim(),
            latitude: _latitude!,
            longitude: _longitude!,
            imageBytes: _imageBytes,
            xFile: _pickedFile,
          );
        },
        maxRetries: 3,
      );

      if (mounted && reportId != null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text("Report submitted successfully!"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload Failed: ${e.toString()}"),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context) ? const BackButton() : null,
        title: const Text("New Infrastructure Report"),
        // SRS Section 6.5: Show network status
        actions: [
          Icon(
            _networkStatus == NetworkStatus.offline
                ? Icons.wifi_off
                : Icons.wifi,
            color: _networkStatus == NetworkStatus.offline
                ? Colors.red
                : Colors.green,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SRS Section 3.2: Title field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Issue Title *",
                  hintText: "e.g., Pothole at Bole Road",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  if (value.trim().length < 5) {
                    return 'Title must be at least 5 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SRS Section 3.2: Description field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: "Description *",
                  hintText: "Describe the issue in detail...",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  if (value.trim().length < 10) {
                    return 'Description must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SRS Section 3.2: Image capture — tap the image to pick (mobile camera) or select (web)
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      height: 250,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: (_imageBytes == null)
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: _pickImage,
                                    child: const Icon(
                                      Icons.add_a_photo,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text("No image selected"),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Tap the image to select",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                    if (_imageBytes != null)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: FloatingActionButton.small(
                          onPressed: _pickImage,
                          child: const Icon(Icons.edit, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 24),

              // SRS Section 3.2: GPS Location
              const Divider(),
              const SizedBox(height: 8),
              Text(
                _locationMessage,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on),
                label: Text(
                  _isGettingLocation
                      ? "Getting Location..."
                      : (_latitude == null || _longitude == null)
                      ? "Set location on map"
                      : "Capture GPS Location",
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // SRS Section 6.3: Privacy option for location
              CheckboxListTile(
                title: const Text("Anonymize location data"),
                subtitle: const Text(
                  "Reduce location precision for privacy",
                  style: TextStyle(fontSize: 12),
                ),
                value: _anonymizeLocation,
                onChanged: (value) {
                  setState(() => _anonymizeLocation = value ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),

              // SRS Section 3.2: Optional location description
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: "Location Description (Optional)",
                  hintText: "e.g., Near Bole Mall, Addis Ababa",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                ),
              ),
              const SizedBox(height: 32),

              // SRS Section 3.2: Submit button
              _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size(double.infinity, 50),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _submitReport,
                      child: const Text(
                        "SUBMIT REPORT",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
