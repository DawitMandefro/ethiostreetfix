import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Logic to log out
  void _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  // STEP 23: AUTHORITY LOGIC WITH AUDIT LOGGING (SRS Section 7)
  void _showStatusUpdateDialog(String docId, String currentStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Resolution"),
        content: const Text(
          "By marking this as Resolved, an audit log will be created with your email and timestamp for accountability.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;

              try {
                // 1. Update the Report Status
                await FirebaseFirestore.instance
                    .collection('reports')
                    .doc(docId)
                    .update({'status': 'Resolved'});

                // 2. Create the Audit Log Entry
                await FirebaseFirestore.instance.collection('audit_logs').add({
                  'action': 'STATUS_CHANGE',
                  'reportId': docId,
                  'performedBy': user?.email ?? 'Unknown',
                  'previousStatus': currentStatus,
                  'newStatus': 'Resolved',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Issue resolved and action logged."),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Error: $e")));
              }
            },
            child: const Text(
              "Confirm & Log",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build filtered lists (Step 21)
  Widget _buildReportList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: statusFilter)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No $statusFilter reports found."));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var report = snapshot.data!.docs[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                // Authorities use long press to trigger management logic
                onLongPress: statusFilter == "Pending"
                    ? () => _showStatusUpdateDialog(report.id, report['status'])
                    : null,
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    report['imageUrl'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image),
                  ),
                ),
                title: Text("Issue #${report.id.substring(0, 5)}"),
                subtitle: Text(report['location']),
                trailing: Icon(
                  Icons.circle,
                  color: statusFilter == "Pending"
                      ? Colors.orange
                      : Colors.green,
                  size: 12,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("EthioStreetFix Dashboard"),
          backgroundColor: Colors.green,
          actions: [
            IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Pending", icon: Icon(Icons.hourglass_empty)),
              Tab(text: "Resolved", icon: Icon(Icons.check_circle_outline)),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildReportList("Pending"), _buildReportList("Resolved")],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportScreen()),
            );
          },
          label: const Text("New Report"),
          icon: const Icon(Icons.add_a_photo),
          backgroundColor: Colors.green,
        ),
      ),
    );
  }
}
