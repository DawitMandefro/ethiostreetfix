import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// SRS Section 3.2: Issue Reporting - Status tracking
enum ReportStatus { pending, inProgress, fixed, rejected }

// SRS Section 3.2: Issue Reporting with GPS location data
class StreetReport {
  final String id;
  final String title;
  final String description;
  final ReportStatus status;
  final String location; // Human-readable address
  final double? latitude; // SRS Section 3.2: GPS-based location data
  final double? longitude; // SRS Section 3.2: GPS-based location data
  final String? imageUrl;
  final String? reportedBy; // User email/ID
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? resolvedBy; // Authority who resolved it
  final String? rejectionReason;

  StreetReport({
    required this.id,
    required this.title,
    required this.description,
    this.status = ReportStatus.pending,
    required this.location,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.reportedBy,
    DateTime? createdAt,
    this.updatedAt,
    this.resolvedBy,
    this.rejectionReason,
  }) : createdAt = createdAt ?? DateTime.now();

  // SRS Section 3.2: Factory constructor from Firestore document
  factory StreetReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StreetReport(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Report',
      description: data['description'] as String? ?? '',
      status: _parseStatus(data['status'] as String?),
      location: data['location'] as String? ?? 'Unknown Location',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      imageUrl: data['imageUrl'] as String?,
      reportedBy: data['reportedBy'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'status': status.name,
      'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (reportedBy != null) 'reportedBy': reportedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (resolvedBy != null) 'resolvedBy': resolvedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }

  /// Create a report from a plain `Map` (used by local/offline fallbacks and tests)
  factory StreetReport.fromMap(Map<String, dynamic> m) {
    return StreetReport(
      id:
          m['id'] as String? ??
          'local-${DateTime.now().millisecondsSinceEpoch}',
      title: m['title'] as String? ?? 'Untitled Report',
      description: m['description'] as String? ?? '',
      status: _parseStatus(m['status'] as String?),
      location: m['location'] as String? ?? 'Unknown Location',
      latitude: (m['latitude'] as num?)?.toDouble(),
      longitude: (m['longitude'] as num?)?.toDouble(),
      imageUrl: m['imageUrl'] as String?,
      reportedBy: m['reportedBy'] as String?,
      createdAt: m['createdAt'] is DateTime
          ? m['createdAt'] as DateTime
          : (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: m['updatedAt'] is DateTime
          ? m['updatedAt'] as DateTime
          : (m['updatedAt'] as Timestamp?)?.toDate(),
      resolvedBy: m['resolvedBy'] as String?,
      rejectionReason: m['rejectionReason'] as String?,
    );
  }

  static ReportStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toLowerCase()) {
      case 'inprogress':
      case 'in_progress':
        return ReportStatus.inProgress;
      case 'fixed':
      case 'resolved':
        return ReportStatus.fixed;
      case 'rejected':
        return ReportStatus.rejected;
      case 'pending':
      default:
        return ReportStatus.pending;
    }
  }

  // SRS Section 3.3: Status color mapping for UI
  Color get statusColor {
    switch (status) {
      case ReportStatus.pending:
        return Colors.orange;
      case ReportStatus.inProgress:
        return Colors.blue;
      case ReportStatus.fixed:
        return Colors.green;
      case ReportStatus.rejected:
        return Colors.red;
    }
  }

  String get statusLabel {
    switch (status) {
      case ReportStatus.pending:
        return 'Pending';
      case ReportStatus.inProgress:
        return 'In Progress';
      case ReportStatus.fixed:
        return 'Fixed';
      case ReportStatus.rejected:
        return 'Rejected';
    }
  }
}
