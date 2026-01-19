import 'package:flutter/material.dart';

class ReportCard extends StatelessWidget {
  final String title;
  final String date;
  final String status;
  final Color statusColor;

  const ReportCard({super.key, 
    required this.title,
    required this.date,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(Icons.warning_amber_rounded, color: statusColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Reported on: $date"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
